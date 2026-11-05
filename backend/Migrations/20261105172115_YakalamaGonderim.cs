using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Kafamdakiler.Migrations
{
    /// <inheritdoc />
    public partial class YakalamaGonderim : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "DenemeSayisi",
                table: "Yakalamalar",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "GonderimBasladiAt",
                table: "Yakalamalar",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "GuncellendiAt",
                table: "Yakalamalar",
                type: "timestamp with time zone",
                nullable: false,
                defaultValue: new DateTimeOffset(new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)));

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "SonDenemeAt",
                table: "Yakalamalar",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "SonHata",
                table: "Yakalamalar",
                type: "character varying(2000)",
                maxLength: 2000,
                nullable: true);

            // Existing captures count as last edited when they were created, not at year 1.
            migrationBuilder.Sql("UPDATE \"Yakalamalar\" SET \"GuncellendiAt\" = \"CreatedAt\"");

            // xmin (the row version in the model) is a PostgreSQL system column that every table already has,
            // so the AddColumn EF generated for it is removed.
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "DenemeSayisi",
                table: "Yakalamalar");

            migrationBuilder.DropColumn(
                name: "GonderimBasladiAt",
                table: "Yakalamalar");

            migrationBuilder.DropColumn(
                name: "GuncellendiAt",
                table: "Yakalamalar");

            migrationBuilder.DropColumn(
                name: "SonDenemeAt",
                table: "Yakalamalar");

            migrationBuilder.DropColumn(
                name: "SonHata",
                table: "Yakalamalar");
        }
    }
}
